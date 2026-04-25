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
  }) = _ProviderInfo;

  factory ProviderInfo.fromJson(Map<String, dynamic> json) => _$ProviderInfoFromJson(json);
}

@Freezed(fromJson: true, toJson: true)
sealed class ProviderModel with _$ProviderModel {
  const factory ProviderModel({
    required String id,
    required String providerID,
    required String name,
    @JsonKey(fromJson: _variantsFromJson, toJson: _variantsToJson) @Default(<String>[]) List<String> variants,
    String? family,
    @Default("active") String status,
    @JsonKey(name: "release_date") String? releaseDate,
  }) = _ProviderModel;

  factory ProviderModel.fromJson(Map<String, dynamic> json) => _$ProviderModelFromJson(json);
}

/// Response from `GET /provider/`.
@Freezed(fromJson: true, toJson: true)
sealed class ProviderListResponse with _$ProviderListResponse {
  const factory ProviderListResponse({
    @JsonKey(readValue: _readProvidersJsonKey) required List<ProviderInfo> providers,
    @JsonKey(name: "default") required Map<String, String> defaults,
    @Default(<String>[]) List<String> connected,
  }) = _ProviderListResponse;

  factory ProviderListResponse.fromJson(Map<String, dynamic> json) => _$ProviderListResponseFromJson(json);
}

List<String> _variantsFromJson(Object? json) {
  if (json is! Map) {
    return const [];
  }

  final enabledVariants = <String>[];
  for (final entry in json.entries) {
    final key = entry.key;
    final value = entry.value;
    if (key is! String) {
      continue;
    }
    if (value is Map && value["disabled"] == true) {
      continue;
    }
    enabledVariants.add(key);
  }

  return enabledVariants;
}

Map<String, dynamic> _variantsToJson(List<String> variants) {
  return {
    for (final variant in variants) variant: {"disabled": false},
  };
}

Object? _readProvidersJsonKey(Map<dynamic, dynamic> json, String key) {
  return json[key] ?? json["all"];
}
