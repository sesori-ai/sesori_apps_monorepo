import "package:freezed_annotation/freezed_annotation.dart";

part "bridge_summary.freezed.dart";
part "bridge_summary.g.dart";

/// A bridge registered with the auth server, as returned by the
/// `/auth/bridges` endpoints and the `bridges` field of `/auth/me`.
@Freezed(fromJson: true, toJson: true)
sealed class BridgeSummary with _$BridgeSummary {
  const factory BridgeSummary({
    required String id,
    required String name,
    required String platform,
    required DateTime addedAt,
    required DateTime? lastSeenAt,
  }) = _BridgeSummary;

  factory BridgeSummary.fromJson(Map<String, dynamic> json) => _$BridgeSummaryFromJson(json);
}
