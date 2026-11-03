// Typed reads over decoded JSON for the code generators in `tool/`.
//
// The OpenAPI spec, the surface files and the event manifests are trusted
// inputs. A value of an unexpected shape means the input is malformed, so a
// read fails loudly with the offending value instead of guessing.

// ignore_for_file: no_slop_linter/prefer_specific_type, untyped decoded JSON is this file's boundary

/// [value] as a JSON object.
Map<String, dynamic> readObject(Object? value) => switch (value) {
  final Map<String, dynamic> object => object,
  _ => throw FormatException('Expected a JSON object', value),
};

/// [value] as a JSON object, or null when it is absent.
Map<String, dynamic>? readObjectOrNull(Object? value) => value == null ? null : readObject(value);

/// [value] as a JSON array.
List<dynamic> readList(Object? value) => switch (value) {
  final List<dynamic> list => list,
  _ => throw FormatException('Expected a JSON array', value),
};

/// [value] as a JSON array, or null when it is absent.
List<dynamic>? readListOrNull(Object? value) => value == null ? null : readList(value);

/// [value] as a JSON string.
String readString(Object? value) => switch (value) {
  final String string => string,
  _ => throw FormatException('Expected a JSON string', value),
};

/// [value] as a JSON string, or null when it is absent.
String? readStringOrNull(Object? value) => value == null ? null : readString(value);
