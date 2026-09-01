import "package:injectable/injectable.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

@LazySingleton(as: AttributionClaimStorage)
class NoOpAttributionClaimStorage() implements AttributionClaimStorage {
  @override
  Future<bool> isClaimed({required AttributionEvent event}) async => true;

  @override
  Future<void> markClaimed({required AttributionEvent event}) async {}
}
