// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T14:11:43.956547Z

import 'package:meta/meta.dart';
import 'reference_config_entry.dart';

@immutable
class ReferenceConfig {
  const ReferenceConfig({required this.value});

  factory ReferenceConfig.fromJson(Map<String, dynamic> json) {
    return ReferenceConfig(
      value: Map<String, ReferenceConfigEntry>.from(
        json.map((k, v) => MapEntry(k, ReferenceConfigEntry.fromJson(v as Object))),
      ),
    );
  }

  final Map<String, ReferenceConfigEntry> value;

  Map<String, dynamic> toJson() {
    return value.map((k, v) => MapEntry(k, v.toJson()));
  }
}
