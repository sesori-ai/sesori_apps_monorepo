import "package:injectable/injectable.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

@LazySingleton(as: ActiveBridgeLocality)
class MobileActiveBridgeLocality() implements ActiveBridgeLocality {
  @override
  bool isLocalBridge({required String bridgeId}) => false;

  @override
  String? get localBridgeId => null;

  @override
  Stream<String?> get localBridgeIdStream => const Stream.empty();
}
