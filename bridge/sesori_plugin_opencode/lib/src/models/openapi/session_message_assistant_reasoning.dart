// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T14:04:07.990847Z

import 'package:meta/meta.dart';

@immutable
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
      "providerMetadata": ?providerMetadata,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionMessageAssistantReasoning &&
          other.type == type &&
          other.id == id &&
          other.text == text &&
          other.providerMetadata == providerMetadata);

  @override
  int get hashCode => Object.hash(type, id, text, providerMetadata);

  final String type;
  final String id;
  final String text;
  final Map<String, Map<String, dynamic>>? providerMetadata;
}
