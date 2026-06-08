// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T13:32:27.999318Z

import 'auth.dart';

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

  final String key;
  final Map<String, String>? metadata;
}
