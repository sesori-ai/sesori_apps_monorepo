// GENERATED FILE - DO NOT EDIT BY HAND


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
      "prompts": prompts,
    };
  }

  final String type;
  final String label;
  final List<dynamic>? prompts;
}
