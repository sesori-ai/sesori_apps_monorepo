// GENERATED FILE - DO NOT EDIT BY HAND


class AgentPartInput {
  const AgentPartInput({
    this.id,
    required this.type,
    required this.name,
    this.source,
  });

  factory AgentPartInput.fromJson(Map<String, dynamic> json) {
    return AgentPartInput(
      id: json["id"] as String?,
      type: json["type"] as String,
      name: json["name"] as String,
      source: json["source"] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": type,
      "name": name,
      "source": source,
    };
  }

  final String? id;
  final String type;
  final String name;
  final Map<String, dynamic>? source;
}
