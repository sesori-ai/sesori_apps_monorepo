import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:sesori_plugin_interface/sesori_plugin_interface.dart';

part 'bridge_startup_lock.freezed.dart';
part 'bridge_startup_lock.g.dart';

@freezed
sealed class BridgeStartupLock with _$BridgeStartupLock {
  const factory BridgeStartupLock({
    required int bridgePid,
    required String? bridgeStartMarker,
  }) = _BridgeStartupLock;

  const BridgeStartupLock._();

  factory BridgeStartupLock.fromJson(Map<String, dynamic> json) => _$BridgeStartupLockFromJson(json);

  bool matchesStartMarkerOf({required ProcessIdentity identity}) {
    if (identity.startMarker != null || bridgeStartMarker != null) {
      return identity.startMarker == bridgeStartMarker;
    }
    // Both markers are null (e.g. Windows). We cannot distinguish a recycled
    // PID from the original owner without additional heuristics, so we
    // conservatively treat the lock as active.
    return true;
  }
}
