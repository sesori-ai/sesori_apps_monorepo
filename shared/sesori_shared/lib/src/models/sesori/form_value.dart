import "package:freezed_annotation/freezed_annotation.dart";

part "form_value.freezed.dart";
part "form_value.g.dart";

/// The wire boundary must not truncate fractional values into integer answers.
final class const FormIntegerConverter() implements JsonConverter<int, num> {
  @override
  int fromJson(num json) {
    if (json is! int) throw const FormatException("Form integers require an integer value");
    return json;
  }

  @override
  int toJson(int object) => object;
}

/// Rejects nonfinite values, including overflowing JSON number exponents.
final class const FiniteFormNumberConverter() implements JsonConverter<double, num> {
  @override
  double fromJson(num json) {
    final value = json.toDouble();
    if (!value.isFinite) throw const FormatException("Form numbers must be finite");
    return value;
  }

  @override
  num toJson(double object) {
    if (!object.isFinite) throw const FormatException("Form numbers must be finite");
    return object;
  }
}

/// Answers contain opaque option IDs; only the owning plugin knows native values.
@Freezed(
  unionKey: "type",
  fallbackUnion: "unknown",
  copyWith: false,
  fromJson: true,
  toJson: true,
  toStringOverride: false,
)
sealed class FormValue with _$FormValue {
  const factory unknown() = FormValueUnknown;
  const factory text({required String value}) = FormTextValue;
  const factory integer({@FormIntegerConverter() required int value}) = FormIntegerValue;
  const factory number({@FiniteFormNumberConverter() required double value}) = FormNumberValue;
  const factory boolean({required bool value}) = FormBooleanValue;
  const factory choice({required String optionId}) = FormChoiceValue;
  const factory choices({required List<String> optionIds}) = FormChoicesValue;

  factory fromJson(Map<String, dynamic> json) => _$FormValueFromJson(json);
}
