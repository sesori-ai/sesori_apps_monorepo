// GENERATED FILE - DO NOT EDIT BY HAND

import 'event.dart';

class EventVcsBranchUpdated implements Event {
  const EventVcsBranchUpdated({
    required this.id,
    required this.properties,
  });

  factory EventVcsBranchUpdated.fromJson(Map<String, dynamic> json) {
    return EventVcsBranchUpdated(
      id: json["id"] as String,
      properties: json["properties"] as Map<String, dynamic>,
    );
  }


  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "vcs.branch.updated",
      "properties": properties,
    };
  }

  final String id;
  final Map<String, dynamic> properties;
}
