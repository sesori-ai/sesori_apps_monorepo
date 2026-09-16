import "package:injectable/injectable.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";

@LazySingleton(as: ActiveBridgeLocality)
class DesktopActiveBridgeLocality({required BridgeStatusTracker statusTracker}) implements ActiveBridgeLocality {
  final BridgeStatusTracker _statusTracker = statusTracker;

  @override
  bool isLocalBridge({required String bridgeId}) {
    final status = _statusTracker.status;
    return status.helperOnline && status.bridgeId == bridgeId;
  }
}
