import "package:freezed_annotation/freezed_annotation.dart";

import "form_value.dart";

part "form_field.freezed.dart";
part "form_field.g.dart";

enum FormTextFormat() {
  unknown,
  plain,
  email,
  uri,
  date,
  dateTime,
}

@Freezed(copyWith: false, fromJson: true, toJson: true, toStringOverride: false)
sealed class FormChoice with _$FormChoice {
  const factory({required String id, required String label}) = _FormChoice;

  factory fromJson(Map<String, dynamic> json) => _$FormChoiceFromJson(json);
}

/// Field IDs and option IDs are independent of native schema keys and values.
@Freezed(copyWith: false, fromJson: true, toJson: true, toStringOverride: false)
sealed class PendingFormField with _$PendingFormField {
  const factory({
    required String id,
    required String label,
    required String? description,
    required bool isRequired,
    required FormFieldSchema schema,
  }) = _PendingFormField;

  factory fromJson(Map<String, dynamic> json) => _$PendingFormFieldFromJson(json);
}

/// Typed defaults and constraints describe the supported normalized form subset.
/// Unknown schemas must be shown as unsupported rather than rendered as text.
@Freezed(
  unionKey: "type",
  fallbackUnion: "unknown",
  copyWith: false,
  fromJson: true,
  toJson: true,
  toStringOverride: false,
)
sealed class FormFieldSchema with _$FormFieldSchema {
  const factory unknown() = FormSchemaUnknown;
  const factory text({
    required String? defaultValue,
    @FormIntegerConverter() required int? minLength,
    @FormIntegerConverter() required int? maxLength,
    @JsonKey(unknownEnumValue: FormTextFormat.unknown) required FormTextFormat format,
  }) = FormTextSchema;
  const factory integer({
    @FormIntegerConverter() required int? defaultValue,
    @FormIntegerConverter() required int? minimum,
    @FormIntegerConverter() required int? maximum,
  }) = FormIntegerSchema;
  const factory number({
    @FiniteFormNumberConverter() required double? defaultValue,
    @FiniteFormNumberConverter() required double? minimum,
    @FiniteFormNumberConverter() required double? maximum,
  }) = FormNumberSchema;
  const factory boolean({required bool? defaultValue}) = FormBooleanSchema;
  const factory choice({required List<FormChoice> options, required String? defaultOptionId}) = FormChoiceSchema;
  const factory choices({
    required List<FormChoice> options,
    required List<String>? defaultOptionIds,
    @FormIntegerConverter() required int? minItems,
    @FormIntegerConverter() required int? maxItems,
  }) = FormChoicesSchema;

  factory fromJson(Map<String, dynamic> json) => _$FormFieldSchemaFromJson(json);
}
