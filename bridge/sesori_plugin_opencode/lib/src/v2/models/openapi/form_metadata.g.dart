// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.3.2 (c0ad18b402eb2827fc1ee71c171b1177b3fc02d1)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

@immutable
class FormMetadata {
  const FormMetadata({required this.json});
  factory FormMetadata.fromJson(Map<String, dynamic> json) {
    return FormMetadata(json: json);
  }
  Map<String, dynamic> toJson() => json;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FormMetadata &&
          const DeepCollectionEquality().equals(other.json, json));

  @override
  int get hashCode => const DeepCollectionEquality().hash(json);

  final Map<String, dynamic> json;
}
