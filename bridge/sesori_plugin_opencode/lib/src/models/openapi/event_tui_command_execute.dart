// GENERATED FILE - DO NOT EDIT BY HAND


class EventTuiCommandExecute {
  const EventTuiCommandExecute({
    required this.type,
    required this.properties,
  });

  factory EventTuiCommandExecute.fromJson(Map<String, dynamic> json) {
    return EventTuiCommandExecute(
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
