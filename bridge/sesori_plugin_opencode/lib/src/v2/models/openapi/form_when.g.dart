// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.0.18 (cd9a14a6b688d4021bee381dfd39d2cef9c0f862)

import 'package:collection/collection.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

@immutable
class FormWhen {
  const FormWhen({
    required this.key,
    required this.op,
    required this.value,
  });

  factory FormWhen.fromJson(Map<String, dynamic> json) {
    return FormWhen(
      key: json["key"] as String,
      op: FormWhenOp.fromJson(json["op"] as String),
      value: json["value"] as Object,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "key": key,
      "op": op.toJson(),
      "value": value,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  FormWhen copyWith({
    String? key,
    FormWhenOp? op,
    Object? value,
  }) {
    return FormWhen(
      key: key ?? this.key,
      op: op ?? this.op,
      value: value ?? this.value,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FormWhen &&
          other.key == key &&
          other.op == op &&
          const DeepCollectionEquality().equals(other.value, value));

  @override
  int get hashCode => Object.hash(key, op, const DeepCollectionEquality().hash(value));

  final String key;
  final FormWhenOp op;
  final Object value;
}

enum FormWhenOp {
  @JsonValue("eq")
  eq,
  @JsonValue("neq")
  neq,

  /// Fallback for values introduced by newer OpenCode servers.
  /// Encodes back to the literal string `unknown`.
  unknown,
  ;

  static FormWhenOp fromJson(String value) {
    switch (value) {
      case "eq":
        return FormWhenOp.eq;
      case "neq":
        return FormWhenOp.neq;
      default:
        return FormWhenOp.unknown;
    }
  }

  String toJson() {
    switch (this) {
      case FormWhenOp.eq:
        return "eq";
      case FormWhenOp.neq:
        return "neq";
      case FormWhenOp.unknown:
        return 'unknown';
    }
  }
}
