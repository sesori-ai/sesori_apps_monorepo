import "package:freezed_annotation/freezed_annotation.dart";

const strictIntJsonConverter = StrictIntJsonConverter();

// ignore: no_slop_linter/prefer_specific_type, converter must inspect untyped JSON before coercion
class const StrictIntJsonConverter() implements JsonConverter<int, Object?> {
  @override
  int fromJson(Object? json) {
    if (json is int) return json;
    throw const FormatException("Expected an integer");
  }

  @override
  Object toJson(int object) => object;
}
