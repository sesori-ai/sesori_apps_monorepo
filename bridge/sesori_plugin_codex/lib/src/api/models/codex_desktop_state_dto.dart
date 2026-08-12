import "package:freezed_annotation/freezed_annotation.dart";

part "codex_desktop_state_dto.freezed.dart";
part "codex_desktop_state_dto.g.dart";

@Freezed(fromJson: true, toJson: false)
sealed class CodexDesktopStateDto with _$CodexDesktopStateDto {
  const factory CodexDesktopStateDto({
    @JsonKey(name: "projectless-thread-ids")
    @CodexProjectlessThreadIdsConverter()
    required Set<String> projectlessThreadIds,
  }) = _CodexDesktopStateDto;

  factory CodexDesktopStateDto.fromJson(Map<String, dynamic> json) => _$CodexDesktopStateDtoFromJson(json);
}

/// Reads only useful string ids from Codex Desktop's independently-versioned
/// state while ignoring missing, malformed, and future-shaped entries.
class const CodexProjectlessThreadIdsConverter() implements JsonConverter<Set<String>, Object?> {
  @override
  Set<String> fromJson(Object? json) {
    if (json is! List) return const {};
    return {
      for (final value in json)
        if (value is String && value.trim().isNotEmpty) value.trim(),
    };
  }

  @override
  Object toJson(Set<String> object) => object.toList(growable: false);
}
