import "package:freezed_annotation/freezed_annotation.dart";

part "session_variant.freezed.dart";

part "session_variant.g.dart";

@Freezed(fromJson: true, toJson: true)
sealed class SessionVariant with _$SessionVariant {
  const factory({required String id}) = _SessionVariant;

  factory fromJson(Map<String, dynamic> json) => _$SessionVariantFromJson(json);
}
