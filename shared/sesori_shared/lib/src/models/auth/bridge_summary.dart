import "package:freezed_annotation/freezed_annotation.dart";

part "bridge_summary.freezed.dart";
part "bridge_summary.g.dart";

/// A bridge registered with the auth server, as returned by the
/// `/auth/bridges` endpoints and the `bridges` field of `/auth/me`.
@Freezed(fromJson: true, toJson: true)
sealed class BridgeSummary with _$BridgeSummary {
  const factory({
    required String id,

    /// The display name: the user's nickname when set, otherwise [hostname].
    required String name,

    /// The name the computer registered with.
    required String hostname,
    @JsonKey(unknownEnumValue: BridgePlatform.unknown) required BridgePlatform platform,
    required BridgeRegistrationStatus status,
    required DateTime addedAt,
    required DateTime? lastSeenAt,
  }) = _BridgeSummary;

  factory fromJson(Map<String, dynamic> json) => _$BridgeSummaryFromJson(json);
}

/// The operating system a bridge registered from.
enum BridgePlatform() {
  macos,
  windows,
  linux,

  /// A platform a newer server reports that this client does not know yet.
  unknown,
}

/// The connectivity the relay last reported to the auth server for a bridge.
/// Named apart from the relay socket's own bridge status.
enum BridgeRegistrationStatus() {
  active,
  inactive,
}
