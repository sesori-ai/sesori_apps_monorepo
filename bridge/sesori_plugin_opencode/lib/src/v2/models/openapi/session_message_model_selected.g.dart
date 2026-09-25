// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.0.16 (3a103fe0aff726a4edc7492f03f7b88195d9e4c9)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'model_ref.g.dart';
import 'session_message_info.g.dart';

@immutable
class SessionMessageModelSelected implements SessionMessageInfo {
  const SessionMessageModelSelected({
    required this.id,
    required this.metadata,
    required this.time,
    required this.model,
    required this.previous,
  });

  factory SessionMessageModelSelected.fromJson(Map<String, dynamic> json) {
    return SessionMessageModelSelected(
      id: json["id"] as String,
      metadata: json["metadata"] as Map<String, dynamic>?,
      time: SessionMessageModelSelectedTime.fromJson(json["time"] as Map<String, dynamic>),
      model: ModelRef.fromJson(json["model"] as Map<String, dynamic>),
      previous: json["previous"] == null ? null : ModelRef.fromJson(json["previous"] as Map<String, dynamic>),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "metadata": ?metadata,
      "time": time.toJson(),
      "type": "model-switched",
      "model": model.toJson(),
      "previous": ?previous?.toJson(),
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  SessionMessageModelSelected copyWith({
    String? id,
    Map<String, dynamic>? metadata,
    SessionMessageModelSelectedTime? time,
    ModelRef? model,
    ModelRef? previous,
  }) {
    return SessionMessageModelSelected(
      id: id ?? this.id,
      metadata: metadata ?? this.metadata,
      time: time ?? this.time,
      model: model ?? this.model,
      previous: previous ?? this.previous,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionMessageModelSelected &&
          other.id == id &&
          const DeepCollectionEquality().equals(other.metadata, metadata) &&
          other.time == time &&
          other.model == model &&
          other.previous == previous);

  @override
  int get hashCode => Object.hash(id, const DeepCollectionEquality().hash(metadata), time, model, previous);

  final String id;
  final Map<String, dynamic>? metadata;
  final SessionMessageModelSelectedTime time;
  final ModelRef model;
  final ModelRef? previous;
}

@immutable
class SessionMessageModelSelectedTime {
  const SessionMessageModelSelectedTime({
    required this.created,
  });

  factory SessionMessageModelSelectedTime.fromJson(Map<String, dynamic> json) {
    return SessionMessageModelSelectedTime(
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
  SessionMessageModelSelectedTime copyWith({
    double? created,
  }) {
    return SessionMessageModelSelectedTime(
      created: created ?? this.created,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionMessageModelSelectedTime &&
          other.created == created);

  @override
  int get hashCode => created.hashCode;

  final double created;
}
