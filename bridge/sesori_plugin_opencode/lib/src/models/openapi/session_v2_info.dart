// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T13:43:24.194471Z

import 'location_ref.dart';

class SessionV2Info {
  const SessionV2Info({
    required this.id,
    this.parentID,
    required this.projectID,
    this.agent,
    this.model,
    required this.cost,
    required this.tokens,
    required this.time,
    required this.title,
    required this.location,
    this.subpath,
  });

  factory SessionV2Info.fromJson(Map<String, dynamic> json) {
    return SessionV2Info(
      id: json["id"] as String,
      parentID: json["parentID"] as String?,
      projectID: json["projectID"] as String,
      agent: json["agent"] as String?,
      model: json["model"] as Map<String, dynamic>?,
      cost: (json["cost"] as num).toDouble(),
      tokens: json["tokens"] as Map<String, dynamic>,
      time: json["time"] as Map<String, dynamic>,
      title: json["title"] as String,
      location: LocationRef.fromJson(json["location"] as Map<String, dynamic>),
      subpath: json["subpath"] as String?,
    );
  }


  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "parentID": ?parentID,
      "projectID": projectID,
      "agent": ?agent,
      "model": ?model,
      "cost": cost,
      "tokens": tokens,
      "time": time,
      "title": title,
      "location": location.toJson(),
      "subpath": ?subpath,
    };
  }

  final String id;
  final String? parentID;
  final String projectID;
  final String? agent;
  final Map<String, dynamic>? model;
  final double cost;
  final Map<String, dynamic> tokens;
  final Map<String, dynamic> time;
  final String title;
  final LocationRef location;
  final String? subpath;
}
