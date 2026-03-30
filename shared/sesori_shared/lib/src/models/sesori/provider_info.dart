import "package:freezed_annotation/freezed_annotation.dart";

part "provider_info.freezed.dart";

part "provider_info.g.dart";

/// Represents an available provider from `GET /provider`.
///
/// We only model the fields relevant for the mobile picker UI.
@Freezed(fromJson: true, toJson: true)
sealed class ProviderInfo with _$ProviderInfo {
  const factory ProviderInfo({
    required String id,
    required String name,
    required Map<String, ProviderModel> models,
    required String? defaultModelID,
  }) = _ProviderInfo;

  factory ProviderInfo.fromJson(Map<String, dynamic> json) => _$ProviderInfoFromJson(json);
}

@Freezed(fromJson: true, toJson: true)
sealed class ProviderModel with _$ProviderModel {
  const factory ProviderModel({
    required String id,
    required String providerID,
    required String name,
    required String? family,
    @Default("active") String status,
    @JsonKey(name: "release_date") required String? releaseDate,
  }) = _ProviderModel;

  factory ProviderModel.fromJson(Map<String, dynamic> json) => _$ProviderModelFromJson(json);
}

/// Response from `GET /provider`.
@Freezed(fromJson: true, toJson: true)
sealed class ProviderListResponse with _$ProviderListResponse {
  const factory ProviderListResponse({
    required List<ProviderInfo> items,
    required bool connectedOnly,
  }) = _ProviderListResponse;

  factory ProviderListResponse.fromJson(Map<String, dynamic> json) => _$ProviderListResponseFromJson(json);
}
