// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

@immutable
class FormatterStatus {
  const FormatterStatus({
    required this.name,
    required this.extensions,
    required this.enabled,
  });

  factory FormatterStatus.fromJson(Map<String, dynamic> json) {
    return FormatterStatus(
      name: json["name"] as String,
      extensions: (json["extensions"] as List<dynamic>).cast<String>(),
      enabled: json["enabled"] as bool,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "name": name,
      "extensions": extensions,
      "enabled": enabled,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FormatterStatus &&
          other.name == name &&
          const DeepCollectionEquality().equals(other.extensions, extensions) &&
          other.enabled == enabled);

  @override
  int get hashCode => Object.hash(name, const DeepCollectionEquality().hash(extensions), enabled);

  final String name;
  final List<String> extensions;
  final bool enabled;
}
