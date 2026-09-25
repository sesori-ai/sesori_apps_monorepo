import "package:json_annotation/json_annotation.dart";

/// A malformed backend payload, retaining its cause without echoing payload
/// content (which can contain prompts or transcripts) in log presentation.
class const V2DecodeException({required final String operation, required final Object innerError})
    implements Exception {
  @override
  String toString() {
    final detail = switch (innerError) {
      CheckedFromJsonException(:final className, :final key, :final innerError) =>
        "$className.$key (${innerError.runtimeType})",
      TypeError() => innerError.toString(),
      FormatException(:final offset) => "FormatException at offset $offset",
      _ => "${innerError.runtimeType}",
    };
    return "OpenCode v2 $operation payload could not be decoded: $detail";
  }
}
