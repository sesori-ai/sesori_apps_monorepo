// GENERATED FILE - DO NOT EDIT BY HAND


class EventTuiSessionSelect {
  const EventTuiSessionSelect({
    required this.type,
    required this.properties,
  });

  factory EventTuiSessionSelect.fromJson(Map<String, dynamic> json) {
    return EventTuiSessionSelect(
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
