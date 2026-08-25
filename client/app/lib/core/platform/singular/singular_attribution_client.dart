import "package:injectable/injectable.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:singular_flutter_sdk/events.dart";

import "singular_static_adapter.dart";

@LazySingleton(as: AttributionClient)
class SingularAttributionClient({required final SingularStaticAdapter _singular}) implements AttributionClient {
  @override
  Future<void> logEvent({required AttributionEvent event}) async {
    final eventName = switch (event) {
      AttributionEvent.accountCreated => Events.sngCompleteRegistration,
      AttributionEvent.accountLogin => Events.sngLogin,
    };
    _singular.event(eventName: eventName);
  }
}
