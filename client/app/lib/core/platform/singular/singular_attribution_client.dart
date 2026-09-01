import "dart:async";

import "package:injectable/injectable.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:singular_flutter_sdk/events.dart";

import "../singular_attribution_startup.dart";
import "singular_static_adapter.dart";

@LazySingleton(as: AttributionClient)
class SingularAttributionClient({
  required final SingularAttributionStartup _startup,
  required final SingularStaticAdapter _singular,
}) implements AttributionClient {
  @override
  bool get isReady => _startup.isStarted;

  @override
  Stream<void> get readinessStream => _startup.readinessStream;

  @override
  Future<void> logEvent({required AttributionEvent event}) async {
    final eventName = switch (event) {
      AttributionEvent.accountCreated => Events.sngCompleteRegistration,
      AttributionEvent.accountLogin => Events.sngLogin,
      AttributionEvent.bridgePaired => "bridge_paired",
      AttributionEvent.firstSessionRun => "first_session_run",
    };
    // Only interactive authentication may lift a deferred start; one-shot
    // activation events require Singular to be running already.
    final canReport = event.isOneShot ? _startup.isStarted : _startup.activateAfterInteractiveAuthentication();
    if (!canReport) return;
    _singular.event(eventName: eventName);
  }
}
