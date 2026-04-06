import "package:freezed_annotation/freezed_annotation.dart";

const dateConverter = DateConverter();

class DateConverter implements JsonConverter<DateTime, String> {
  const DateConverter();

  @override
  DateTime fromJson(String json) => DateTime.parse(json).toLocal();

  @override
  String toJson(DateTime object) {
    final year = object.year.toString().padLeft(4, "0");
    final month = object.month.toString().padLeft(2, "0");
    final day = object.day.toString().padLeft(2, "0");
    return "$year-$month-$day";
  }
}
