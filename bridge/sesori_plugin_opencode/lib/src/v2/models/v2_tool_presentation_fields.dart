import "package:freezed_annotation/freezed_annotation.dart";

part "v2_tool_presentation_fields.freezed.dart";
part "v2_tool_presentation_fields.g.dart";

/// A display projection of opaque tool input/metadata. Unrelated tools may use
/// these keys with non-text values; those values are not presentation text.
@Freezed(copyWith: false, toJson: false)
sealed class V2ToolPresentationFields with _$V2ToolPresentationFields {
  const factory({
    @JsonKey(fromJson: _textOrNull) required String? command,
    @JsonKey(fromJson: _textOrNull) required String? title,
  }) = _V2ToolPresentationFields;

  factory fromJson(Map<String, dynamic> json) => _$V2ToolPresentationFieldsFromJson(json);
}

String? _textOrNull(Object? value) => value is String ? value : null;
