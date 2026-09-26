import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../models/openapi/form_answer.g.dart";
import "../models/openapi/form_boolean_field.g.dart";
import "../models/openapi/form_info.g.dart";
import "../models/openapi/form_integer_field.g.dart";
import "../models/openapi/form_multiselect_field.g.dart";
import "../models/openapi/form_number_field.g.dart";
import "../models/openapi/form_option.g.dart";
import "../models/openapi/form_string_field.g.dart";
import "../models/openapi/form_value.g.dart";
import "../repositories/v2_model_mapper.dart";

/// Reverses the visible-field projection without inventing hidden answers.
class const V2FormAnswerMapper() {
  FormAnswer map({required FormInfo form, required List<List<String>> answers}) {
    final fields = V2ModelMapper.visibleFormFields(form: form);
    if (answers.length != fields.length) _invalid(message: "The number of form answers does not match the questions.");
    final result = <String, FormValue>{};
    for (final (index, field) in fields.indexed) {
      final choices = answers[index];
      // An empty entry means deliberately unanswered, not false or an empty value.
      if (choices.isEmpty) continue;
      final (key, value) = switch (field) {
        FormStringField(:final key, :final options) => (
          key,
          _option(
            answer: _single(choices: choices),
            options: options ?? const [],
          ),
        ),
        FormMultiselectField(:final key, :final options) => (
          key,
          [for (final choice in choices) _option(answer: choice, options: options)],
        ),
        FormBooleanField(:final key) => (
          key,
          bool.tryParse(_single(choices: choices)) ?? _invalid(message: "Expected true or false for $key."),
        ),
        FormNumberField(:final key) || FormIntegerField(:final key) => (
          key,
          num.tryParse(_single(choices: choices)) ?? _invalid(message: "Expected a number for $key."),
        ),
        _ => throw StateError("Only supported visible fields reach answer projection"),
      };
      // The generated union preserves scalar numbers/booleans as well as strings/lists.
      result[key] = FormValue.fromJson(value);
    }
    return FormAnswer(value: result);
  }

  String _single({required List<String> choices}) {
    if (choices.length != 1) _invalid(message: "This form field accepts one answer.");
    return choices.single;
  }

  String _option({required String answer, required List<FormOption> options}) =>
      options.where((option) => option.label == answer).firstOrNull?.value ?? answer;

  Never _invalid({required String message}) =>
      throw PluginOperationException("replyToQuestion", statusCode: 400, message: message);
}
