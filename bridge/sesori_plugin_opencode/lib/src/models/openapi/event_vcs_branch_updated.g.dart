// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.17.7 (4ed4f749e644ffb5b279fb30b7b915e743d80142)

import 'package:meta/meta.dart';
import 'event.g.dart';

@immutable
class EventVcsBranchUpdated implements Event {
  const EventVcsBranchUpdated({
    required this.id,
    required this.properties,
  });

  factory EventVcsBranchUpdated.fromJson(Map<String, dynamic> json) {
    return EventVcsBranchUpdated(
      id: json["id"] as String,
      properties: EventVcsBranchUpdatedProperties.fromJson(json["properties"] as Map<String, dynamic>),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "vcs.branch.updated",
      "properties": properties.toJson(),
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  EventVcsBranchUpdated copyWith({
    String? id,
    EventVcsBranchUpdatedProperties? properties,
  }) {
    return EventVcsBranchUpdated(
      id: id ?? this.id,
      properties: properties ?? this.properties,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventVcsBranchUpdated &&
          other.id == id &&
          other.properties == properties);

  @override
  int get hashCode => Object.hash(id, properties);

  final String id;
  final EventVcsBranchUpdatedProperties properties;
}

@immutable
class EventVcsBranchUpdatedProperties {
  const EventVcsBranchUpdatedProperties({
    required this.branch,
  });

  factory EventVcsBranchUpdatedProperties.fromJson(Map<String, dynamic> json) {
    return EventVcsBranchUpdatedProperties(
      branch: json["branch"] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "branch": ?branch,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  EventVcsBranchUpdatedProperties copyWith({
    String? branch,
  }) {
    return EventVcsBranchUpdatedProperties(
      branch: branch ?? this.branch,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventVcsBranchUpdatedProperties &&
          other.branch == branch);

  @override
  int get hashCode => branch.hashCode;

  final String? branch;
}
