import "package:freezed_annotation/freezed_annotation.dart";

import "bridge_summary.dart";

part "bridges_list_response.freezed.dart";
part "bridges_list_response.g.dart";

/// Response of `GET /auth/bridges`: the bridges registered with the
/// authenticated account.
@Freezed(fromJson: true, toJson: false)
sealed class BridgesListResponse with _$BridgesListResponse {
  const factory BridgesListResponse({
    required List<BridgeSummary> bridges,
  }) = _BridgesListResponse;

  factory BridgesListResponse.fromJson(Map<String, dynamic> json) => _$BridgesListResponseFromJson(json);
}
