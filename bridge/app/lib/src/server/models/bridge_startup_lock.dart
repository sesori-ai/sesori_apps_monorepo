import 'package:freezed_annotation/freezed_annotation.dart';

part 'bridge_startup_lock.freezed.dart';
part 'bridge_startup_lock.g.dart';

@freezed
sealed class BridgeStartupLock with _$BridgeStartupLock {
  const factory BridgeStartupLock({
    required int bridgePid,
    required String? bridgeStartMarker,
  }) = _BridgeStartupLock;

  factory BridgeStartupLock.fromJson(Map<String, dynamic> json) =>
      _$BridgeStartupLockFromJson(json);
}
