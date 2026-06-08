// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T14:24:06.228114Z

import 'package:meta/meta.dart';

@immutable
class JSONSchema {
  const JSONSchema({required this.json});
  factory JSONSchema.fromJson(Map<String, dynamic> json) {
    return JSONSchema(json: json);
  }
  Map<String, dynamic> toJson() => json;
  final Map<String, dynamic> json;
}
