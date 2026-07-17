import "dart:async";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;

import "../acp_approval_registry.dart";
import "../acp_stdio_client.dart";

class AcpApprovalListener {
  AcpApprovalListener({
    required AcpApprovalRegistry registry,
    required Stream<AcpServerRequest> requests,
  }) : _registry = registry,
       _requests = requests;

  final AcpApprovalRegistry _registry;
  final Stream<AcpServerRequest> _requests;
  StreamSubscription<AcpServerRequest>? _subscription;

  void attach() {
    if (_subscription != null) return;
    // Ownership transfers to this listener and is released by dispose().
    // ignore: cancel_subscriptions
    final subscription = _requests.listen(_registry.handleRequest);
    _subscription = subscription;
  }

  Future<void> reset() => _registry.reset();

  Future<void> dispose() async {
    final subscription = _subscription;
    _subscription = null;
    try {
      await subscription?.cancel();
    } on Object catch (error, stackTrace) {
      Log.w("[acp] failed to cancel approval listener", error, stackTrace);
    }
    await _registry.dispose();
  }
}
