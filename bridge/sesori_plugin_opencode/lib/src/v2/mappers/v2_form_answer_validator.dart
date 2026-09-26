import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../models/openapi/form_answer.g.dart";
import "../models/openapi/form_info.g.dart";
import "../models/openapi/form_integer_field.g.dart";
import "../models/openapi/form_number_field.g.dart";

/// Numeric fields use free text in Sesori; check their native constraints before dispatch.
/// Other constraints, including conditional/external fields, remain native-authoritative.
class const V2FormAnswerValidator() {
  void validate({required FormInfo form, required FormAnswer answer}) {
    for (final field in form.fields.items) {
      final constraint = switch (field) {
        FormNumberField(:final key, :final minimum, :final maximum) => (
          key: key,
          minimum: minimum,
          maximum: maximum,
          integer: false,
        ),
        FormIntegerField(:final key, :final minimum, :final maximum) => (
          key: key,
          minimum: minimum,
          maximum: maximum,
          integer: true,
        ),
        _ => null,
      };
      if (constraint == null || !answer.value.containsKey(constraint.key)) continue;
      final value = answer.value[constraint.key]!.toJson();
      if (value is! num || !value.isFinite || (constraint.integer && value != value.truncateToDouble())) {
        _invalid(message: "Expected a finite ${constraint.integer ? 'integer' : 'number'} for ${constraint.key}.");
      }
      final minimum = _bound(value: constraint.minimum);
      final maximum = _bound(value: constraint.maximum);
      if (minimum != null && value < minimum) _invalid(message: "Answer is below the minimum for ${constraint.key}.");
      if (maximum != null && value > maximum) _invalid(message: "Answer is above the maximum for ${constraint.key}.");
    }
  }

  // Effect's numeric schema encodes non-finite bounds as strings. Preserve the
  // native comparison semantics rather than treating every string as no bound.
  num? _bound({required Object? value}) => switch (value) {
    null => null,
    final num number => number,
    final String text => num.parse(text),
    _ => throw StateError("Unexpected native numeric bound"),
  };

  Never _invalid({required String message}) =>
      throw PluginOperationException("replyToQuestion", statusCode: 400, message: message);
}
