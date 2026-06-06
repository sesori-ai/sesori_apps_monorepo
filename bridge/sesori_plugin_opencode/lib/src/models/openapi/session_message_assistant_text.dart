// GENERATED FILE - DO NOT EDIT BY HAND


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
