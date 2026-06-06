// GENERATED FILE - DO NOT EDIT BY HAND


class ToolListItem {
  const ToolListItem({
    required this.id,
    required this.description,
    required this.parameters,
  });

  factory ToolListItem.fromJson(Map<String, dynamic> json) {
    return ToolListItem(
      id: json["id"] as String,
      description: json["description"] as String,
      parameters: json["parameters"],
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "description": description,
      "parameters": parameters,
    };
  }

  final String id;
  final String description;
  final dynamic parameters;
}
