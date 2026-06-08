// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T13:32:28.053825Z


class SessionMessageAssistantText {
  const SessionMessageAssistantText({
    required this.type,
    required this.id,
    required this.text,
  });

  factory SessionMessageAssistantText.fromJson(Map<String, dynamic> json) {
    return SessionMessageAssistantText(
      type: json["type"] as String,
      id: json["id"] as String,
      text: json["text"] as String,
    );
  }


  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "type": type,
      "id": id,
      "text": text,
    };
  }

  final String type;
  final String id;
  final String text;
}
