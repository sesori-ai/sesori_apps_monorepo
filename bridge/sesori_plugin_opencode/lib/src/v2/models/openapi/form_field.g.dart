// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.0.16 (3a103fe0aff726a4edc7492f03f7b88195d9e4c9)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'form_boolean_field.g.dart';
import 'form_external_field.g.dart';
import 'form_integer_field.g.dart';
import 'form_multiselect_field.g.dart';
import 'form_number_field.g.dart';
import 'form_string_field.g.dart';

@immutable
abstract interface class FormField {
  const FormField();

  /// Serialize the underlying variant. Variants must override this.
  ///
  /// The return type is `Object?` (not `Map<String, dynamic>`)
  /// because some unions are string-or-object and the string
  /// variant encodes as the scalar itself, not a wrapped map.
  /// Callers pass the result straight to `jsonEncode` or
  /// another `toJson()`, both of which accept `Object?`.
  Object? toJson();

  factory FormField.fromJson(Object json) {
    final map = json as Map<String, dynamic>;
    final discriminator = map["type"];
    switch (discriminator) {
      case "string":
        return FormStringField.fromJson(map);
      case "number":
        return FormNumberField.fromJson(map);
      case "integer":
        return FormIntegerField.fromJson(map);
      case "boolean":
        return FormBooleanField.fromJson(map);
      case "multiselect":
        return FormMultiselectField.fromJson(map);
      case "external":
        return FormExternalField.fromJson(map);
      default:
        return FormFieldUnknown(raw: map);
    }
  }
}

/// Fallback variant for an unrecognized [FormField] payload shape.
/// Carries the raw JSON so newer OpenCode servers do not break
/// decoding; `toJson` returns the payload unchanged.
@immutable
class FormFieldUnknown implements FormField {
  const FormFieldUnknown({required this.raw});

  final Object? raw;

  @override
  Object? toJson() => raw;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FormFieldUnknown &&
          const DeepCollectionEquality().equals(other.raw, raw));

  @override
  int get hashCode => const DeepCollectionEquality().hash(raw);
}
