import "package:freezed_annotation/freezed_annotation.dart";

import "../../converters/date_converter.dart";

part "provider_info.freezed.dart";

part "provider_info.g.dart";

/// Represents an available provider from `GET /provider`.
///
/// We only model the fields relevant for the mobile picker UI.
@Freezed(fromJson: true, toJson: true)
sealed class ProviderInfo with _$ProviderInfo {
  const factory({
    required String id,
    required String name,
    required Map<String, ProviderModel> models,
    required String? defaultModelID,
  }) = _ProviderInfo;

  factory fromJson(Map<String, dynamic> json) => _$ProviderInfoFromJson(json);
}

@Freezed(fromJson: true, toJson: true)
sealed class ProviderModel with _$ProviderModel {
  const factory({
    required String id,
    required String providerID,
    required String name,
    required List<String> variants,
    required String? family,
    @Default(true) bool isAvailable,
    @dateConverter required DateTime? releaseDate,
  }) = _ProviderModel;

  factory fromJson(Map<String, dynamic> json) => _$ProviderModelFromJson(json);
}

/// Response from `GET /provider`.
@Freezed(fromJson: true, toJson: true)
sealed class ProviderListResponse with _$ProviderListResponse {
  const factory({
    required List<ProviderInfo> items,
    required bool connectedOnly,
  }) = _ProviderListResponse;

  factory fromJson(Map<String, dynamic> json) => _$ProviderListResponseFromJson(json);
}
