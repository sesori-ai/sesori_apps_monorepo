// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.4.1 (6f0514052a3c859894ad01bb14cc14dda1e44b96)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'form_value.g.dart';

@immutable
class FormAnswer {
  const FormAnswer({required this.value});

  factory FormAnswer.fromJson(Map<String, dynamic> json) {
    return FormAnswer(
      value: Map<String, FormValue>.from(
        json.map((k, v) => MapEntry(k, FormValue.fromJson(v as Object))),
      ),
    );
  }

  final Map<String, FormValue> value;

  Map<String, dynamic> toJson() {
    return value.map((k, v) => MapEntry(k, v.toJson()));
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FormAnswer &&
          const DeepCollectionEquality().equals(other.value, value));

  @override
  int get hashCode => const DeepCollectionEquality().hash(value);
}
