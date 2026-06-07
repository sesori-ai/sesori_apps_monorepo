// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-07T10:22:51.674343Z

import 'reference_config_entry.dart';

class ReferenceConfig {
  const ReferenceConfig({required this.value});

  factory ReferenceConfig.fromJson(Map<String, dynamic> json) {
    return ReferenceConfig(
      value: Map<String, ReferenceConfigEntry>.from(
        json.map((k, v) => MapEntry(k, ReferenceConfigEntry.fromJson(v as Map<String, dynamic>))),
      ),
    );
  }

  final Map<String, ReferenceConfigEntry> value;

  Map<String, dynamic> toJson() {
    return value.map((k, v) => MapEntry(k, v.toJson()));
  }
}
