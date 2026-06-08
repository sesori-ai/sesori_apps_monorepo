// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T14:24:06.240693Z

import 'package:meta/meta.dart';

@immutable
class ProviderAuthMethod {
  const ProviderAuthMethod({
    required this.type,
    required this.label,
    this.prompts,
  });

  factory ProviderAuthMethod.fromJson(Map<String, dynamic> json) {
    return ProviderAuthMethod(
      type: json["type"] as String,
      label: json["label"] as String,
      prompts: (json["prompts"] as List<dynamic>?)?.cast<Object>(),
    );
  }


  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "type": type,
      "label": label,
      "prompts": ?prompts,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProviderAuthMethod &&
          other.type == type &&
          other.label == label &&
          other.prompts == prompts);

  @override
  int get hashCode => Object.hash(type, label, prompts);

  final String type;
  final String label;
  final List<Object>? prompts;
}
