// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.0.18 (cd9a14a6b688d4021bee381dfd39d2cef9c0f862)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

@immutable
abstract interface class FormValue {
  const FormValue();

  /// Serialize the underlying variant. Variants must override this.
  ///
  /// The return type is `Object?` (not `Map<String, dynamic>`)
  /// because some unions are string-or-object and the string
  /// variant encodes as the scalar itself, not a wrapped map.
  /// Callers pass the result straight to `jsonEncode` or
  /// another `toJson()`, both of which accept `Object?`.
  Object? toJson();

  factory FormValue.fromJson(Object json) {
    if (json is String) {
      return FormValue00Inline.fromJson(json);
    }
    if (json is List) {
      return FormValue01Inline.fromJson(json as List<dynamic>);
    }
    return FormValueUnknown(raw: json);
  }
}

@immutable
class FormValue00Inline implements FormValue {
  const FormValue00Inline({required this.value});
  factory FormValue00Inline.fromJson(String json) {
    return FormValue00Inline(value: json);
  }
  @override
  Object? toJson() => value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FormValue00Inline && other.value == value);

  @override
  int get hashCode => value.hashCode;

  final String value;
}


@immutable
class FormValue01Inline implements FormValue {
  const FormValue01Inline({required this.items});
  factory FormValue01Inline.fromJson(List<dynamic> json) {
    return FormValue01Inline(items: json.cast<String>());
  }
  @override
  Object? toJson() => items;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FormValue01Inline &&
          const DeepCollectionEquality().equals(other.items, items));

  @override
  int get hashCode => const DeepCollectionEquality().hash(items);

  final List<String> items;
}


/// Fallback variant for an unrecognized [FormValue] payload shape.
/// Carries the raw JSON so newer OpenCode servers do not break
/// decoding; `toJson` returns the payload unchanged.
@immutable
class FormValueUnknown implements FormValue {
  const FormValueUnknown({required this.raw});

  final Object? raw;

  @override
  Object? toJson() => raw;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FormValueUnknown &&
          const DeepCollectionEquality().equals(other.raw, raw));

  @override
  int get hashCode => const DeepCollectionEquality().hash(raw);
}
