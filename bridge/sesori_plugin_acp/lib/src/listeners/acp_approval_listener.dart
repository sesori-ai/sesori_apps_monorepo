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
  // The analyzer cannot trace cancellation through this listener's dispose().
  // ignore: cancel_subscriptions
  StreamSubscription<AcpServerRequest>? _subscription;

  void attach() {
    if (_subscription != null) return;
    _subscription = _requests.listen(_registry.handleRequest);
  }

  Future<void> reset() async {
    await _cancelSubscription();
    await _registry.reset();
  }

  Future<void> dispose() async {
    await _cancelSubscription();
    await _registry.dispose();
  }

  Future<void> _cancelSubscription() async {
    final subscription = _subscription;
    _subscription = null;
    try {
      await subscription?.cancel();
    } on Object catch (error, stackTrace) {
      Log.w("[acp] failed to cancel approval listener", error, stackTrace);
    }
  }
}
