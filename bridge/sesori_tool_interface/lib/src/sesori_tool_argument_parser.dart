import "package:json_annotation/json_annotation.dart" show CheckedFromJsonException, UnrecognizedKeysException;

/// Arguments that do not fit a tool's schema. [reason] names the field and is
/// shown to the agent.
final class const InvalidToolArguments({required final String reason}) implements Exception;

/// Reads a tool's arguments into its model, or throws [InvalidToolArguments]
/// naming the field that is wrong.
///
/// Strict-schema providers make the model fill every field, and it fills the
/// ones it means to leave out with "". No argument has a meaningful empty
/// value, so an empty string reads as absent.
final class const SesoriToolArgumentParser({
  /// Where each nested argument model sits in the arguments, such as
  /// `sections[].`, keyed by the class name checked decoding reports.
  required final Map<String, String> nestedPlaces,

  /// The fields each kind of a nested argument needs, keyed by the
  /// argument's field and then its `kind`. Shared models read an unknown kind
  /// as unknown and fail on a missing field without naming it, so both are
  /// checked before decoding.
  required final Map<String, Map<String, List<String>>> kindFields,
}) {
  static const String _seeSchema = "see its input schema.";

  T parse<T>({required Map<String, Object?> json, required T Function(Map<String, dynamic> json) fromJson}) {
    final present = {
      for (final MapEntry(:key, :value) in json.entries)
        if (value != "") key: value,
    };
    _checkKinds(json: present);
    try {
      return fromJson(present);
    } on CheckedFromJsonException catch (error) {
      // A nested argument's failure names only its own key, so its place in
      // the arguments comes from the model that failed.
      final place = nestedPlaces[error.className] ?? "";
      final reason = switch (error.key) {
        final key? when error.map[key] == null => "$place$key is required.",
        final key? => "$place$key is not valid; see its input schema.",
        null => switch (error.innerError) {
          UnrecognizedKeysException(:final unrecognizedKeys) =>
            "$place${unrecognizedKeys.first} is not an argument; see its input schema.",
          _ => _seeSchema,
        },
      };
      throw InvalidToolArguments(reason: reason);
    } on Object {
      throw const InvalidToolArguments(reason: _seeSchema);
    }
  }

  void _checkKinds({required Map<String, Object?> json}) {
    for (final MapEntry(key: field, value: kinds) in kindFields.entries) {
      if (json[field] case final Map<String, dynamic> value) {
        final kind = value["kind"];
        final needed = kinds[kind];
        if (needed == null) {
          throw InvalidToolArguments(reason: "$field.kind must be one of ${kinds.keys.join(", ")}.");
        }
        for (final subfield in needed) {
          if (value[subfield] == null) {
            throw InvalidToolArguments(reason: "$field.$subfield is required when $field.kind is $kind.");
          }
        }
      }
    }
  }
}

/// [value], or [InvalidToolArguments] when it is blank, which is how
/// strict-schema providers fill a field they leave out.
String requiredToolText({required String value, required String field}) {
  if (value.trim().isEmpty) throw InvalidToolArguments(reason: "$field is required.");
  return value;
}

/// [value], or null when it is blank: absent, for strict-schema providers.
String? optionalToolText({required String? value}) => value == null || value.trim().isEmpty ? null : value;
