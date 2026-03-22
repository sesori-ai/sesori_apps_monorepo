import "package:json_annotation/json_annotation.dart";

enum DevicePlatform {
  @JsonValue("ios")
  ios,
  @JsonValue("android")
  android,
}
