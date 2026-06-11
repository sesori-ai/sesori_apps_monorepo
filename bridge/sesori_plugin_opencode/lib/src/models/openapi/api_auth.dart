// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'auth.dart';

@immutable
class ApiAuth implements Auth {
  const ApiAuth({
    required this.key,
    this.metadata,
  });

  factory ApiAuth.fromJson(Map<String, dynamic> json) {
    return ApiAuth(
      key: json["key"] as String,
      metadata: (json["metadata"] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, v as String)),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "type": "api",
      "key": key,
      "metadata": ?metadata,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ApiAuth &&
          other.key == key &&
          const DeepCollectionEquality().equals(other.metadata, metadata));

  @override
  int get hashCode => Object.hash(key, const DeepCollectionEquality().hash(metadata));

  final String key;
  final Map<String, String>? metadata;
}
