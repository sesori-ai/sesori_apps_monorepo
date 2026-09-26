// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.0.18 (cd9a14a6b688d4021bee381dfd39d2cef9c0f862)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'location_public_ref.g.dart';
import 'session_message_info.g.dart';

@immutable
class SessionMessageLocationSwitched implements SessionMessageInfo {
  const SessionMessageLocationSwitched({
    required this.id,
    required this.metadata,
    required this.time,
    required this.projectID,
    required this.subpath,
    required this.location,
    required this.previous,
  });

  factory SessionMessageLocationSwitched.fromJson(Map<String, dynamic> json) {
    return SessionMessageLocationSwitched(
      id: json["id"] as String,
      metadata: json["metadata"] as Map<String, dynamic>?,
      time: SessionMessageLocationSwitchedTime.fromJson(json["time"] as Map<String, dynamic>),
      projectID: json["projectID"] as String?,
      subpath: json["subpath"] as String?,
      location: LocationPublicRef.fromJson(json["location"] as Map<String, dynamic>),
      previous: json["previous"] == null ? null : SessionMessageLocationSwitchedPrevious.fromJson(json["previous"] as Map<String, dynamic>),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "metadata": ?metadata,
      "time": time.toJson(),
      "type": "location-switched",
      "projectID": ?projectID,
      "subpath": ?subpath,
      "location": location.toJson(),
      "previous": ?previous?.toJson(),
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  SessionMessageLocationSwitched copyWith({
    String? id,
    Map<String, dynamic>? metadata,
    SessionMessageLocationSwitchedTime? time,
    String? projectID,
    String? subpath,
    LocationPublicRef? location,
    SessionMessageLocationSwitchedPrevious? previous,
  }) {
    return SessionMessageLocationSwitched(
      id: id ?? this.id,
      metadata: metadata ?? this.metadata,
      time: time ?? this.time,
      projectID: projectID ?? this.projectID,
      subpath: subpath ?? this.subpath,
      location: location ?? this.location,
      previous: previous ?? this.previous,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionMessageLocationSwitched &&
          other.id == id &&
          const DeepCollectionEquality().equals(other.metadata, metadata) &&
          other.time == time &&
          other.projectID == projectID &&
          other.subpath == subpath &&
          other.location == location &&
          other.previous == previous);

  @override
  int get hashCode => Object.hash(id, const DeepCollectionEquality().hash(metadata), time, projectID, subpath, location, previous);

  final String id;
  final Map<String, dynamic>? metadata;
  final SessionMessageLocationSwitchedTime time;
  final String? projectID;
  final String? subpath;
  final LocationPublicRef location;
  final SessionMessageLocationSwitchedPrevious? previous;
}

@immutable
class SessionMessageLocationSwitchedTime {
  const SessionMessageLocationSwitchedTime({
    required this.created,
  });

  factory SessionMessageLocationSwitchedTime.fromJson(Map<String, dynamic> json) {
    return SessionMessageLocationSwitchedTime(
      created: (json["created"] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "created": created,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  SessionMessageLocationSwitchedTime copyWith({
    double? created,
  }) {
    return SessionMessageLocationSwitchedTime(
      created: created ?? this.created,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionMessageLocationSwitchedTime &&
          other.created == created);

  @override
  int get hashCode => created.hashCode;

  final double created;
}

@immutable
class SessionMessageLocationSwitchedPrevious {
  const SessionMessageLocationSwitchedPrevious({
    required this.location,
    required this.projectID,
    required this.subpath,
  });

  factory SessionMessageLocationSwitchedPrevious.fromJson(Map<String, dynamic> json) {
    return SessionMessageLocationSwitchedPrevious(
      location: LocationPublicRef.fromJson(json["location"] as Map<String, dynamic>),
      projectID: json["projectID"] as String?,
      subpath: json["subpath"] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "location": location.toJson(),
      "projectID": ?projectID,
      "subpath": ?subpath,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  SessionMessageLocationSwitchedPrevious copyWith({
    LocationPublicRef? location,
    String? projectID,
    String? subpath,
  }) {
    return SessionMessageLocationSwitchedPrevious(
      location: location ?? this.location,
      projectID: projectID ?? this.projectID,
      subpath: subpath ?? this.subpath,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionMessageLocationSwitchedPrevious &&
          other.location == location &&
          other.projectID == projectID &&
          other.subpath == subpath);

  @override
  int get hashCode => Object.hash(location, projectID, subpath);

  final LocationPublicRef location;
  final String? projectID;
  final String? subpath;
}
