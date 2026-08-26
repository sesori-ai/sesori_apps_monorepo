import "package:injectable/injectable.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

@LazySingleton(as: AttributionClient)
class NoOpAttributionClient() implements AttributionClient {
  @override
  Future<void> logEvent({required AttributionEvent event}) async {}
}
