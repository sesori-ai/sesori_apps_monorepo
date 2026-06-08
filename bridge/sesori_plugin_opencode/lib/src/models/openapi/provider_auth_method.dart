// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T07:51:39.998731Z


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
      prompts: (json["prompts"] as List<dynamic>?)?.cast<dynamic>(),
    );
  }


  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "type": type,
      "label": label,
      "prompts": ?prompts,
    };
  }

  final String type;
  final String label;
  final List<dynamic>? prompts;
}
