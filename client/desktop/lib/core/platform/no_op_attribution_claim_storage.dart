import "package:injectable/injectable.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

@LazySingleton(as: AttributionClaimStorage)
class NoOpAttributionClaimStorage() implements AttributionClaimStorage {
  @override
  Future<bool> isClaimed({required String claimKey}) async => false;

  @override
  Future<void> markClaimed({required String claimKey}) async {}
}
