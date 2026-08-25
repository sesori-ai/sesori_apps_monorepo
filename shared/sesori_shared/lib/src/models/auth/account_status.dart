import "package:freezed_annotation/freezed_annotation.dart";

/// Whether this authentication operation created a Sesori account.
enum AccountStatus() {
  @JsonValue("created")
  created,

  @JsonValue("existing")
  existing,

  /// A newer server status that this client does not yet understand.
  unknown,
}
