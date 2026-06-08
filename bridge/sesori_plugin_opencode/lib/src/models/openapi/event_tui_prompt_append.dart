// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T08:11:58.898444Z


class EventTuiPromptAppend {
  const EventTuiPromptAppend({
    required this.type,
    required this.properties,
  });

  factory EventTuiPromptAppend.fromJson(Map<String, dynamic> json) {
    return EventTuiPromptAppend(
      type: json["type"] as String,
      properties: json["properties"] as Map<String, dynamic>,
    );
  }


  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "type": type,
      "properties": properties,
    };
  }

  final String type;
  final Map<String, dynamic> properties;
}
