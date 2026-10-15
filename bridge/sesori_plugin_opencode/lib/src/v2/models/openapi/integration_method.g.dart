// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.0.24 (e7a34f09bfd9134dfade5a8ddb843f7030bc9a69)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'form_fields_1.g.dart';
import 'form_fields_2.g.dart';

@immutable
sealed class IntegrationMethod {
  const IntegrationMethod();

  /// Serialize the underlying variant. Variants must override this.
  ///
  /// The return type is `Object?` (not `Map<String, dynamic>`)
  /// because some unions are string-or-object and the string
  /// variant encodes as the scalar itself, not a wrapped map.
  /// Callers pass the result straight to `jsonEncode` or
  /// another `toJson()`, both of which accept `Object?`.
  Object? toJson();

  factory IntegrationMethod.fromJson(Object json) {
    final map = json as Map<String, dynamic>;
    final discriminator = map["type"];
    switch (discriminator) {
      case "oauth":
        return IntegrationOAuthMethod.fromJson(map);
      case "command":
        return IntegrationCommandMethod.fromJson(map);
      case "key":
        return IntegrationKeyMethod.fromJson(map);
      case "env":
        return IntegrationEnvMethod.fromJson(map);
      default:
        return IntegrationMethodUnknown(raw: map);
    }
  }
}

@immutable
final class IntegrationOAuthMethod implements IntegrationMethod {
  const IntegrationOAuthMethod({
    required this.id,
    required this.label,
    required this.form,
  });

  factory IntegrationOAuthMethod.fromJson(Map<String, dynamic> json) {
    return IntegrationOAuthMethod(
      id: json["id"] as String,
      label: json["label"] as String,
      form: json["form"] == null ? null : FormFields1.fromJson(json["form"] as List<dynamic>),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "oauth",
      "label": label,
      "form": ?form?.toJson(),
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  IntegrationOAuthMethod copyWith({
    String? id,
    String? label,
    FormFields1? form,
  }) {
    return IntegrationOAuthMethod(
      id: id ?? this.id,
      label: label ?? this.label,
      form: form ?? this.form,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is IntegrationOAuthMethod &&
          other.id == id &&
          other.label == label &&
          other.form == form);

  @override
  int get hashCode => Object.hash(id, label, form);

  final String id;
  final String label;
  final FormFields1? form;
}


@immutable
final class IntegrationCommandMethod implements IntegrationMethod {
  const IntegrationCommandMethod({
    required this.id,
    required this.label,
    required this.command,
  });

  factory IntegrationCommandMethod.fromJson(Map<String, dynamic> json) {
    return IntegrationCommandMethod(
      id: json["id"] as String,
      label: json["label"] as String,
      command: (json["command"] as List<dynamic>).cast<String>(),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "command",
      "label": label,
      "command": command,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  IntegrationCommandMethod copyWith({
    String? id,
    String? label,
    List<String>? command,
  }) {
    return IntegrationCommandMethod(
      id: id ?? this.id,
      label: label ?? this.label,
      command: command ?? this.command,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is IntegrationCommandMethod &&
          other.id == id &&
          other.label == label &&
          const DeepCollectionEquality().equals(other.command, command));

  @override
  int get hashCode => Object.hash(id, label, const DeepCollectionEquality().hash(command));

  final String id;
  final String label;
  final List<String> command;
}


@immutable
final class IntegrationKeyMethod implements IntegrationMethod {
  const IntegrationKeyMethod({
    required this.label,
    required this.form,
  });

  factory IntegrationKeyMethod.fromJson(Map<String, dynamic> json) {
    return IntegrationKeyMethod(
      label: json["label"] as String?,
      form: json["form"] == null ? null : FormFields2.fromJson(json["form"] as List<dynamic>),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "type": "key",
      "label": ?label,
      "form": ?form?.toJson(),
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  IntegrationKeyMethod copyWith({
    String? label,
    FormFields2? form,
  }) {
    return IntegrationKeyMethod(
      label: label ?? this.label,
      form: form ?? this.form,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is IntegrationKeyMethod &&
          other.label == label &&
          other.form == form);

  @override
  int get hashCode => Object.hash(label, form);

  final String? label;
  final FormFields2? form;
}


@immutable
final class IntegrationEnvMethod implements IntegrationMethod {
  const IntegrationEnvMethod({
    required this.names,
  });

  factory IntegrationEnvMethod.fromJson(Map<String, dynamic> json) {
    return IntegrationEnvMethod(
      names: (json["names"] as List<dynamic>).cast<String>(),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "type": "env",
      "names": names,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  IntegrationEnvMethod copyWith({
    List<String>? names,
  }) {
    return IntegrationEnvMethod(
      names: names ?? this.names,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is IntegrationEnvMethod &&
          const DeepCollectionEquality().equals(other.names, names));

  @override
  int get hashCode => const DeepCollectionEquality().hash(names);

  final List<String> names;
}


/// Fallback variant for an unrecognized [IntegrationMethod] payload shape.
/// Carries the raw JSON so newer OpenCode servers do not break
/// decoding; `toJson` returns the payload unchanged.
@immutable
final class IntegrationMethodUnknown implements IntegrationMethod {
  const IntegrationMethodUnknown({required this.raw});

  final Object? raw;

  @override
  Object? toJson() => raw;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is IntegrationMethodUnknown &&
          const DeepCollectionEquality().equals(other.raw, raw));

  @override
  int get hashCode => const DeepCollectionEquality().hash(raw);
}
