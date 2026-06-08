// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T14:11:43.974650Z

import 'package:meta/meta.dart';

@immutable
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
      parameters: json["parameters"] as Object,
    );
  }


  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "description": description,
      "parameters": parameters,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ToolListItem &&
          other.id == id &&
          other.description == description &&
          other.parameters == parameters);

  @override
  int get hashCode => Object.hash(id, description, parameters);

  final String id;
  final String description;
  final Object parameters;
}
