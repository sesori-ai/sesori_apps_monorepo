import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

/// Owns the supported native schema subset and its request-local opaque aliases.
final class ClaudeFormSchema._({
  required List<PluginFormField> fields,
  required Map<String, String> nativeKeys,
  required Map<String, Map<String, String>> nativeOptions,
}) {
  final List<PluginFormField> fields = List.unmodifiable(fields);
  final Map<String, String> _nativeKeys = Map.unmodifiable(nativeKeys);
  final Map<String, Map<String, String>> _nativeOptions = Map.unmodifiable({
    for (final entry in nativeOptions.entries) entry.key: Map<String, String>.unmodifiable(entry.value),
  });

  /// Unsupported schema is an explicit decline at the pending-request boundary.
  static ClaudeFormSchema? parse({required Object? schema}) {
    try {
      final root = _object(value: schema);
      _keys(schema: root, allowed: const {"type", "properties", "required", "title", "description", r"$schema"});
      if (root["type"] != "object") throw const FormatException("Unsupported form root");
      final properties = _object(value: root["properties"]);
      final requiredFields = root.containsKey("required") ? _strings(value: root["required"]) : const <String>[];
      if (!requiredFields.every(properties.containsKey)) throw const FormatException("Unknown required field");
      final fields = <PluginFormField>[];
      final nativeKeys = <String, String>{};
      final nativeOptions = <String, Map<String, String>>{};
      for (final entry in properties.entries) {
        final id = "field-${fields.length}";
        final raw = _object(value: entry.value);
        final options = <String, String>{};
        final fieldSchema = _field(schema: raw, nativeOptions: options);
        final field = PluginFormField(
          id: id,
          label: _optional<String>(schema: raw, key: "title") ?? entry.key,
          description: _optional<String>(schema: raw, key: "description"),
          isRequired: requiredFields.contains(entry.key),
          schema: fieldSchema,
        );
        final defaultValue = _defaultValue(schema: fieldSchema);
        if (defaultValue != null && _issue(schema: fieldSchema, value: defaultValue) != null) {
          throw const FormatException("Invalid form default");
        }
        fields.add(field);
        nativeKeys[id] = entry.key;
        nativeOptions[id] = options;
      }
      return ClaudeFormSchema._(fields: fields, nativeKeys: nativeKeys, nativeOptions: nativeOptions);
    } on FormatException {
      // The caller renders a capability warning and sends an explicit decline.
      return null;
    }
  }

  Map<String, PluginFormValidationIssue> validate({required Map<String, PluginFormValue> values}) {
    final errors = <String, PluginFormValidationIssue>{
      for (final id in values.keys)
        if (!_nativeKeys.containsKey(id)) id: PluginFormValidationIssue.invalidChoice,
    };
    for (final field in fields) {
      final value = values[field.id];
      if (value == null) {
        if (field.isRequired) errors[field.id] = PluginFormValidationIssue.required;
      } else if (_issue(schema: field.schema, value: value) case final issue?) {
        errors[field.id] = issue;
      }
    }
    return errors;
  }

  /// Only call after validation; native names and option values stay here.
  Map<String, Object?> encode({required Map<String, PluginFormValue> values}) => {
    for (final entry in values.entries)
      _nativeKeys[entry.key]!: switch (entry.value) {
        PluginFormTextValue(:final value) => value,
        PluginFormIntegerValue(:final value) => value,
        PluginFormNumberValue(:final value) => value,
        PluginFormBooleanValue(:final value) => value,
        PluginFormChoiceValue(:final optionId) => _nativeOptions[entry.key]![optionId]!,
        PluginFormChoicesValue(:final optionIds) => [for (final id in optionIds) _nativeOptions[entry.key]![id]!],
      },
  };

  static PluginFormSchema _field({required Map<String, Object?> schema, required Map<String, String> nativeOptions}) {
    const metadata = {"type", "title", "description", "default"};
    switch (schema["type"]) {
      case "boolean":
        _keys(schema: schema, allowed: metadata);
        return PluginFormBooleanSchema(
          defaultValue: _optional<bool>(schema: schema, key: "default"),
        );
      case "integer":
        _keys(schema: schema, allowed: {...metadata, "minimum", "maximum"});
        final minimum = _optional<int>(schema: schema, key: "minimum");
        final maximum = _optional<int>(schema: schema, key: "maximum");
        _bounds(minimum: minimum, maximum: maximum);
        return PluginFormIntegerSchema(
          defaultValue: _optional<int>(schema: schema, key: "default"),
          minimum: minimum,
          maximum: maximum,
        );
      case "number":
        _keys(schema: schema, allowed: {...metadata, "minimum", "maximum"});
        final minimum = _number(schema: schema, key: "minimum");
        final maximum = _number(schema: schema, key: "maximum");
        _bounds(minimum: minimum, maximum: maximum);
        return PluginFormNumberSchema(
          defaultValue: _number(schema: schema, key: "default"),
          minimum: minimum,
          maximum: maximum,
        );
      case "string":
        if (schema.containsKey("enum") || schema.containsKey("oneOf")) {
          _keys(schema: schema, allowed: {...metadata, "enum", "oneOf"});
          final options = _choices(schema: schema, nativeOptions: nativeOptions);
          final defaultValue = _optional<String>(schema: schema, key: "default");
          return PluginFormChoiceSchema(
            options: options,
            defaultOptionId: defaultValue == null ? null : _optionId(value: defaultValue, options: nativeOptions),
          );
        }
        _keys(schema: schema, allowed: {...metadata, "minLength", "maxLength"});
        final minimum = _count(schema: schema, key: "minLength");
        final maximum = _count(schema: schema, key: "maxLength");
        _bounds(minimum: minimum, maximum: maximum);
        return PluginFormTextSchema(
          defaultValue: _optional<String>(schema: schema, key: "default"),
          minLength: minimum,
          maxLength: maximum,
          format: PluginFormTextFormat.plain,
        );
      case "array":
        _keys(schema: schema, allowed: {...metadata, "items", "minItems", "maxItems"});
        final items = _object(value: schema["items"]);
        _keys(schema: items, allowed: const {"type", "enum", "oneOf", "anyOf"});
        if (items["type"] != "string") throw const FormatException("Unsupported form array");
        final options = _choices(schema: items, nativeOptions: nativeOptions);
        final minimum = _count(schema: schema, key: "minItems");
        final maximum = _count(schema: schema, key: "maxItems");
        _bounds(minimum: minimum, maximum: maximum);
        final defaults = schema.containsKey("default") ? _strings(value: schema["default"]) : null;
        return PluginFormChoicesSchema(
          options: options,
          defaultOptionIds: defaults?.map((value) => _optionId(value: value, options: nativeOptions)).toList(),
          minItems: minimum,
          maxItems: maximum,
        );
      default:
        throw const FormatException("Unsupported form field");
    }
  }

  static List<PluginFormChoice> _choices({
    required Map<String, Object?> schema,
    required Map<String, String> nativeOptions,
  }) {
    final representations = ["enum", "oneOf", "anyOf"].where(schema.containsKey).toList();
    if (representations.length != 1) {
      throw const FormatException("Unsupported form options");
    }
    final choices = <PluginFormChoice>[];
    final raw = representations.single == "enum" ? _strings(value: schema["enum"]) : schema[representations.single];
    if (raw is! List || raw.isEmpty) throw const FormatException("Missing form options");
    for (final item in raw) {
      final option = schema.containsKey("enum") ? <String, Object?>{"const": item} : _object(value: item);
      _keys(schema: option, allowed: const {"const", "title", "description"});
      final value = option["const"];
      if (value is! String || nativeOptions.containsValue(value)) throw const FormatException("Invalid form option");
      final id = "option-${choices.length}";
      nativeOptions[id] = value;
      choices.add(
        PluginFormChoice(
          id: id,
          label: _optional<String>(schema: option, key: "title") ?? (value.isEmpty ? "Empty value" : value),
        ),
      );
    }
    return choices;
  }

  static PluginFormValidationIssue? _issue({required PluginFormSchema schema, required PluginFormValue value}) {
    switch ((schema, value)) {
      case (PluginFormTextSchema(:final minLength, :final maxLength), PluginFormTextValue(:final value)):
        return _outside(value: value.runes.length, minimum: minLength, maximum: maxLength)
            ? PluginFormValidationIssue.invalidLength
            : null;
      case (PluginFormIntegerSchema(:final minimum, :final maximum), PluginFormIntegerValue(:final value)):
        return _outside(value: value, minimum: minimum, maximum: maximum) ? PluginFormValidationIssue.outOfRange : null;
      case (PluginFormNumberSchema(:final minimum, :final maximum), PluginFormNumberValue(:final value)):
        return !value.isFinite || _outside(value: value, minimum: minimum, maximum: maximum)
            ? PluginFormValidationIssue.outOfRange
            : null;
      case (PluginFormBooleanSchema(), PluginFormBooleanValue()):
        return null;
      case (PluginFormChoiceSchema(:final options), PluginFormChoiceValue(:final optionId)):
        return options.any((option) => option.id == optionId) ? null : PluginFormValidationIssue.invalidChoice;
      case (
        PluginFormChoicesSchema(:final options, :final minItems, :final maxItems),
        PluginFormChoicesValue(:final optionIds),
      ):
        if (!optionIds.every((id) => options.any((option) => option.id == id))) {
          return PluginFormValidationIssue.invalidChoice;
        }
        return _outside(value: optionIds.length, minimum: minItems, maximum: maxItems)
            ? PluginFormValidationIssue.invalidLength
            : null;
      default:
        return PluginFormValidationIssue.invalidType;
    }
  }

  static PluginFormValue? _defaultValue({required PluginFormSchema schema}) => switch (schema) {
    PluginFormTextSchema(:final defaultValue) => defaultValue == null ? null : PluginFormTextValue(value: defaultValue),
    PluginFormIntegerSchema(:final defaultValue) =>
      defaultValue == null ? null : PluginFormIntegerValue(value: defaultValue),
    PluginFormNumberSchema(:final defaultValue) =>
      defaultValue == null ? null : PluginFormNumberValue(value: defaultValue),
    PluginFormBooleanSchema(:final defaultValue) =>
      defaultValue == null ? null : PluginFormBooleanValue(value: defaultValue),
    PluginFormChoiceSchema(:final defaultOptionId) =>
      defaultOptionId == null ? null : PluginFormChoiceValue(optionId: defaultOptionId),
    PluginFormChoicesSchema(:final defaultOptionIds) =>
      defaultOptionIds == null ? null : PluginFormChoicesValue(optionIds: defaultOptionIds),
  };

  static String _optionId({required String value, required Map<String, String> options}) => options.entries
      .firstWhere((entry) => entry.value == value, orElse: () => throw const FormatException("Invalid form default"))
      .key;

  // ignore: no_slop_linter/prefer_specific_type, native JSON schema boundary
  static Map<String, Object?> _object({required Object? value}) {
    if (value is! Map || value.keys.any((key) => key is! String)) throw const FormatException("Invalid form object");
    return value.cast<String, Object?>();
  }

  // ignore: no_slop_linter/prefer_specific_type, native JSON schema boundary
  static List<String> _strings({required Object? value}) {
    if (value is! List || value.any((item) => item is! String)) throw const FormatException("Invalid form list");
    return value.cast<String>();
  }

  static void _keys({required Map<String, Object?> schema, required Set<String> allowed}) {
    if (!allowed.containsAll(schema.keys)) throw const FormatException("Unsupported form constraint");
  }

  static T? _optional<T>({required Map<String, Object?> schema, required String key}) {
    if (!schema.containsKey(key)) return null;
    final value = schema[key];
    if (value is! T) throw const FormatException("Invalid form constraint type");
    return value;
  }

  static double? _number({required Map<String, Object?> schema, required String key}) {
    final value = _optional<num>(schema: schema, key: key)?.toDouble();
    if (value != null && !value.isFinite) throw const FormatException("Nonfinite form constraint");
    return value;
  }

  static int? _count({required Map<String, Object?> schema, required String key}) {
    final value = _optional<int>(schema: schema, key: key);
    if (value != null && value < 0) throw const FormatException("Negative form constraint");
    return value;
  }

  static void _bounds({required num? minimum, required num? maximum}) {
    if (minimum != null && maximum != null && minimum > maximum) throw const FormatException("Inverted form bounds");
  }

  static bool _outside({required num value, required num? minimum, required num? maximum}) =>
      (minimum != null && value < minimum) || (maximum != null && value > maximum);
}
