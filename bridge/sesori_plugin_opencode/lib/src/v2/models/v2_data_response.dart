import "package:freezed_annotation/freezed_annotation.dart";

part "v2_data_response.freezed.dart";
part "v2_data_response.g.dart";

/// Minimal envelope shared by global `{data}` and location-scoped responses.
/// The request selects the location; only the typed payload is consumed here.
@Freezed(genericArgumentFactories: true, copyWith: false, toJson: false)
sealed class V2DataResponse<T> with _$V2DataResponse<T> {
  const factory({required T data}) = _V2DataResponse<T>;

  factory fromJson(Map<String, dynamic> json, T Function(Object?) fromJsonT) =>
      _$V2DataResponseFromJson(json, fromJsonT);
}
