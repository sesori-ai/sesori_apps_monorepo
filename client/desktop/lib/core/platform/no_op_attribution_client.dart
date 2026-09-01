import "dart:async";

import "package:injectable/injectable.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

@LazySingleton(as: AttributionClient)
class NoOpAttributionClient() implements AttributionClient {
  @override
  bool get isReady => false;

  @override
  Stream<void> get readinessStream => const Stream<void>.empty();

  @override
  Future<void> logEvent({required AttributionEvent event}) async {}
}
