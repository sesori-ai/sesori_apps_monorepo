// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T13:32:28.054199Z


class SessionMessageAssistantTool {
  const SessionMessageAssistantTool({
    required this.type,
    required this.id,
    required this.name,
    this.provider,
    required this.state,
    required this.time,
  });

  factory SessionMessageAssistantTool.fromJson(Map<String, dynamic> json) {
    return SessionMessageAssistantTool(
      type: json["type"] as String,
      id: json["id"] as String,
      name: json["name"] as String,
      provider: json["provider"] as Map<String, dynamic>?,
      state: json["state"] as Object,
      time: json["time"] as Map<String, dynamic>,
    );
  }


  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "type": type,
      "id": id,
      "name": name,
      "provider": ?provider,
      "state": state,
      "time": time,
    };
  }

  final String type;
  final String id;
  final String name;
  final Map<String, dynamic>? provider;
  final Object state;
  final Map<String, dynamic> time;
}
