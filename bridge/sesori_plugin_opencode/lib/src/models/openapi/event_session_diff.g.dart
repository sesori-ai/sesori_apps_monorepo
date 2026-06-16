// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.17.3 (8c8011336163d7e7fb24a6a4a049cdb1f6e6ee74)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'event.g.dart';
import 'snapshot_file_diff.g.dart';

@immutable
class EventSessionDiff implements Event {
  const EventSessionDiff({
    required this.id,
    required this.properties,
  });

  factory EventSessionDiff.fromJson(Map<String, dynamic> json) {
    return EventSessionDiff(
      id: json["id"] as String,
      properties: EventSessionDiffProperties.fromJson(json["properties"] as Map<String, dynamic>),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "session.diff",
      "properties": properties.toJson(),
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  EventSessionDiff copyWith({
    String? id,
    EventSessionDiffProperties? properties,
  }) {
    return EventSessionDiff(
      id: id ?? this.id,
      properties: properties ?? this.properties,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventSessionDiff &&
          other.id == id &&
          other.properties == properties);

  @override
  int get hashCode => Object.hash(id, properties);

  final String id;
  final EventSessionDiffProperties properties;
}

@immutable
class EventSessionDiffProperties {
  const EventSessionDiffProperties({
    required this.sessionID,
    required this.diff,
  });

  factory EventSessionDiffProperties.fromJson(Map<String, dynamic> json) {
    return EventSessionDiffProperties(
      sessionID: json["sessionID"] as String,
      diff: (json["diff"] as List<dynamic>).map((e) => SnapshotFileDiff.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "sessionID": sessionID,
      "diff": diff.map((e) => e.toJson()).toList(),
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  EventSessionDiffProperties copyWith({
    String? sessionID,
    List<SnapshotFileDiff>? diff,
  }) {
    return EventSessionDiffProperties(
      sessionID: sessionID ?? this.sessionID,
      diff: diff ?? this.diff,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventSessionDiffProperties &&
          other.sessionID == sessionID &&
          const DeepCollectionEquality().equals(other.diff, diff));

  @override
  int get hashCode => Object.hash(sessionID, const DeepCollectionEquality().hash(diff));

  final String sessionID;
  final List<SnapshotFileDiff> diff;
}
