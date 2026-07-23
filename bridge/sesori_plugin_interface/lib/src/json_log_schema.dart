/// Returns a bounded, value-free description of a JSON-compatible value.
///
/// String values are represented as `String` unless their key is included in
/// [enumKeyNames] and their value is a short identifier token. Those opted-in
/// values are rendered as `enum("value")` so unknown enum values remain useful
/// when diagnosing parser failures.
///
/// Enum key names apply at every nesting level. Callers must only opt in keys
/// whose values are non-sensitive schema metadata throughout their JSON domain.
/// Map keys that do not look like schema identifiers are redacted. Collection
/// size and recursion depth are capped so malformed input cannot flood logs.
String jsonSchemaForLog({
  required Object? value,
  required Set<String> enumKeyNames,
}) => _jsonSchemaForLog(
  value: value,
  enumKeyNames: enumKeyNames,
  fieldName: null,
  depth: 0,
);

String _jsonSchemaForLog({
  required Object? value,
  required Set<String> enumKeyNames,
  required String? fieldName,
  required int depth,
}) {
  const maxDepth = 5;
  const maxEntries = 16;
  const maxListItems = 8;

  if (value == null) return "null";
  if (value is String) {
    if (fieldName != null && enumKeyNames.contains(fieldName) && _schemaIdentifierPattern.hasMatch(value)) {
      return 'enum("$value")';
    }
    return "String";
  }
  if (value is bool) return "bool";
  if (value is num) return value.runtimeType.toString();
  if (value is List) {
    if (depth >= maxDepth) return "List";
    if (value.isEmpty) return "List<empty>";
    final itemSchemas = <String>{};
    for (final item in value.take(maxListItems)) {
      itemSchemas.add(
        _jsonSchemaForLog(
          value: item,
          enumKeyNames: enumKeyNames,
          fieldName: null,
          depth: depth + 1,
        ),
      );
    }
    final suffix = value.length > maxListItems ? ",…" : "";
    return "List<${itemSchemas.join("|")}$suffix>";
  }
  if (value is Map) {
    if (depth >= maxDepth) return "Map";
    final entries = value.entries.take(maxEntries).map((entry) {
      final key = entry.key;
      final safeKey = key is String && _schemaKeyPattern.hasMatch(key) ? key : "<${key.runtimeType}-key>";
      return "$safeKey:${_jsonSchemaForLog(
        value: entry.value,
        enumKeyNames: enumKeyNames,
        fieldName: safeKey,
        depth: depth + 1,
      )}";
    });
    final suffix = value.length > maxEntries ? ",…" : "";
    return "{${entries.join(",")}$suffix}";
  }
  return value.runtimeType.toString();
}

final RegExp _schemaIdentifierPattern = RegExp(
  r"^[A-Za-z][A-Za-z0-9_.-]{0,63}$",
);
final RegExp _schemaKeyPattern = RegExp(
  r"^[A-Za-z_][A-Za-z0-9_.-]{0,63}$",
);
