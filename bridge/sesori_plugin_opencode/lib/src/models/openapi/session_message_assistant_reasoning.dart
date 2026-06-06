// GENERATED FILE - DO NOT EDIT BY HAND


class SessionMessageAssistantReasoning {
  const SessionMessageAssistantReasoning({
    required this.type,
    required this.id,
    required this.text,
    this.providerMetadata,
  });

  factory SessionMessageAssistantReasoning.fromJson(Map<String, dynamic> json) {
    return SessionMessageAssistantReasoning(
      type: json["type"] as String,
      id: json["id"] as String,
      text: json["text"] as String,
      providerMetadata: (json["providerMetadata"] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, v as Map<String, dynamic>)),
    );
  }


  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "type": type,
      "id": id,
      "text": text,
      "providerMetadata": providerMetadata,
    };
  }

  final String type;
  final String id;
  final String text;
  final Map<String, Map<String, dynamic>>? providerMetadata;
}
