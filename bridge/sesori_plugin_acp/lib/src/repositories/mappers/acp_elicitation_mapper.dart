import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

const int _maxTextLength = 500;
const String _suggestedTextLabel = "Use suggested text";

sealed class AcpElicitationForm {
  const AcpElicitationForm();
}

final class AcpSupportedElicitationForm extends AcpElicitationForm {
  const AcpSupportedElicitationForm({
    required this.questions,
    required List<AcpElicitationField> fields,
  }) : _fields = fields;

  final List<PluginQuestionInfo> questions;
  final List<AcpElicitationField> _fields;

  Map<String, Object?> buildContent({required List<List<String>> answers}) {
    final content = <String, Object?>{};
    for (var index = 0; index < _fields.length; index++) {
      final selected = index < answers.length ? answers[index] : const <String>[];
      final value = _fields[index].encode(selected: selected);
      if (value != null) content[_fields[index].key] = value;
    }
    return content;
  }
}

final class AcpUnsupportedElicitationForm extends AcpElicitationForm {
  const AcpUnsupportedElicitationForm({required this.reason});

  /// Privacy-safe structural reason. Never contains labels, defaults, or text.
  final String reason;
}

sealed class AcpElicitationField {
  const AcpElicitationField({required this.key});

  final String key;

  Object? encode({required List<String> selected});
}

final class _StringField extends AcpElicitationField {
  const _StringField({required super.key, required this.suggestedText});

  final String? suggestedText;

  @override
  Object? encode({required List<String> selected}) {
    if (selected.isEmpty) return null;
    final value = selected.first;
    if (value == _suggestedTextLabel && suggestedText != null) return suggestedText;
    return value;
  }
}

final class _BooleanField extends AcpElicitationField {
  const _BooleanField({required super.key});

  @override
  Object? encode({required List<String> selected}) {
    if (selected.isEmpty) return null;
    return switch (selected.first) {
      "Yes" => true,
      "No" => false,
      _ => null,
    };
  }
}

final class _EnumField extends AcpElicitationField {
  const _EnumField({required super.key, required this.valuesByLabel});

  final Map<String, String> valuesByLabel;

  @override
  Object? encode({required List<String> selected}) => selected.isEmpty ? null : valuesByLabel[selected.first];
}

/// Maps the standard ACP v1 `elicitation/create` form shape to Sesori questions.
class AcpElicitationMapper {
  const AcpElicitationMapper();

  AcpElicitationForm parse({required Map<String, dynamic> params}) {
    final mode = params["mode"];
    if (mode != "form") {
      return AcpUnsupportedElicitationForm(
        reason: "unsupported elicitation mode: ${_token(mode)}",
      );
    }
    final schema = _map(params["requestedSchema"]);
    if (schema == null || schema["type"] != "object") {
      return AcpUnsupportedElicitationForm(
        reason: "unsupported schema type: ${_token(schema?["type"])}",
      );
    }
    final properties = _map(schema["properties"]);
    if (properties == null || properties.isEmpty) {
      return const AcpUnsupportedElicitationForm(reason: "form has no properties");
    }

    final requestMessage = _bounded(_string(params["message"]) ?? "Input requested");
    final schemaTitle = _bounded(_string(schema["title"]) ?? requestMessage);
    final questions = <PluginQuestionInfo>[];
    final fields = <AcpElicitationField>[];
    for (final entry in properties.entries) {
      final property = _map(entry.value);
      if (property == null) {
        return const AcpUnsupportedElicitationForm(reason: "property is not an object");
      }
      final mapped = _mapProperty(
        key: entry.key,
        property: property,
        requestMessage: requestMessage,
        schemaTitle: schemaTitle,
      );
      if (mapped == null) {
        return AcpUnsupportedElicitationForm(
          reason: "unsupported property type: ${_token(property["type"])}",
        );
      }
      questions.add(mapped.question);
      fields.add(mapped.field);
    }
    return AcpSupportedElicitationForm(questions: questions, fields: fields);
  }

  ({PluginQuestionInfo question, AcpElicitationField field})? _mapProperty({
    required String key,
    required Map<String, dynamic> property,
    required String requestMessage,
    required String schemaTitle,
  }) {
    final title = _bounded(_string(property["title"]) ?? schemaTitle);
    final questionText = _bounded(
      _string(property["description"]) ?? _string(property["title"]) ?? requestMessage,
    );
    switch (property["type"]) {
      case "boolean":
        return (
          question: PluginQuestionInfo(
            question: questionText,
            header: title,
            options: const [
              PluginQuestionOption(label: "Yes", description: ""),
              PluginQuestionOption(label: "No", description: ""),
            ],
            multiple: false,
            custom: false,
          ),
          field: _BooleanField(key: key),
        );
      case "string":
        final choices = _enumChoices(property);
        final hasChoices = property.containsKey("enum") || property.containsKey("oneOf");
        if (hasChoices && choices == null) return null;
        if (choices != null) {
          return (
            question: PluginQuestionInfo(
              question: questionText,
              header: title,
              options: [
                for (final choice in choices)
                  PluginQuestionOption(label: choice.label, description: choice.description),
              ],
              multiple: false,
              custom: false,
            ),
            field: _EnumField(
              key: key,
              valuesByLabel: {for (final choice in choices) choice.label: choice.value},
            ),
          );
        }
        final suggested = _string(property["default"]);
        return (
          question: PluginQuestionInfo(
            question: questionText,
            header: title,
            options: [
              if (suggested != null)
                PluginQuestionOption(
                  label: _suggestedTextLabel,
                  description: _bounded(suggested),
                ),
            ],
            multiple: false,
            custom: true,
          ),
          field: _StringField(key: key, suggestedText: suggested),
        );
      default:
        return null;
    }
  }

  List<({String label, String value, String description})>? _enumChoices(
    Map<String, dynamic> property,
  ) {
    final rawOneOf = property["oneOf"];
    if (rawOneOf is List) {
      final choices = <({String label, String value, String description})>[];
      final usedLabels = <String>{};
      for (final raw in rawOneOf) {
        final item = _map(raw);
        final value = _string(item?["const"]);
        if (item == null || value == null) return null;
        final baseLabel = _string(item["title"]) ?? value;
        final label = _uniqueLabel(base: baseLabel, used: usedLabels);
        choices.add((
          label: label,
          value: value,
          description: _bounded(_string(item["description"]) ?? ""),
        ));
      }
      return choices.isEmpty ? null : choices;
    }
    final rawEnum = property["enum"];
    if (rawEnum is! List) return null;
    final values = rawEnum.whereType<String>().toList(growable: false);
    if (values.length != rawEnum.length || values.isEmpty) return null;
    final usedLabels = <String>{};
    return [
      for (final value in values)
        (
          label: _uniqueLabel(base: value, used: usedLabels),
          value: value,
          description: "",
        ),
    ];
  }

  static String _uniqueLabel({required String base, required Set<String> used}) {
    var label = base;
    var suffix = 2;
    while (!used.add(label)) {
      label = "$base ($suffix)";
      suffix++;
    }
    return label;
  }

  static Map<String, dynamic>? _map(Object? value) => value is Map ? value.cast<String, dynamic>() : null;

  static String? _string(Object? value) => value is String && value.isNotEmpty ? value : null;

  static String _token(Object? value) => value is String ? value : value.runtimeType.toString();

  static String _bounded(String value) =>
      value.length <= _maxTextLength ? value : "${value.substring(0, _maxTextLength)}...";
}
