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

  /// The supervised bridge's id, kept while its helper is offline so the
  /// desktop can still target its own computer.
  @override
  String? get localBridgeId => _statusTracker.status.bridgeId;
}
