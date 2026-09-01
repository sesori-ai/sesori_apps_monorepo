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
  Future<void> logEvent({required AttributionEvent event}) async {
    final eventName = switch (event) {
      AttributionEvent.accountCreated => Events.sngCompleteRegistration,
      AttributionEvent.accountLogin => Events.sngLogin,
      AttributionEvent.bridgePaired => "bridge_paired",
      AttributionEvent.firstSessionRun => "first_session_run",
    };
    final canReport = switch (event) {
      AttributionEvent.accountCreated ||
      AttributionEvent.accountLogin => _startup.activateAfterInteractiveAuthentication(),
      AttributionEvent.bridgePaired || AttributionEvent.firstSessionRun => _startup.isStarted,
    };
    if (!canReport) return;
    _singular.event(eventName: eventName);
  }
}
