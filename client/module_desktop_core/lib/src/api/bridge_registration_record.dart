import "package:freezed_annotation/freezed_annotation.dart";

part "bridge_registration_record.freezed.dart";
part "bridge_registration_record.g.dart";

/// The desktop's persisted bridge registration together with its owning
/// account. The owner prevents a later account on the same machine from
/// treating an earlier account's offline-unregister handle as its own.
@Freezed(fromJson: true, toJson: true)
sealed class BridgeRegistrationRecord with _$BridgeRegistrationRecord {
  const factory({
    required String bridgeId,
    required String accountId,
  }) = _BridgeRegistrationRecord;

  factory fromJson(Map<String, dynamic> json) => _$BridgeRegistrationRecordFromJson(json);
}
