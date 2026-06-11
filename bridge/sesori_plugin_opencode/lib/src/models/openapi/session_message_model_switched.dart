// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'session_message.dart';

@immutable
class SessionMessageModelSwitched implements SessionMessage {
  const SessionMessageModelSwitched({
    required this.id,
    this.metadata,
    required this.time,
    required this.model,
  });

  factory SessionMessageModelSwitched.fromJson(Map<String, dynamic> json) {
    return SessionMessageModelSwitched(
      id: json["id"] as String,
      metadata: json["metadata"] as Map<String, dynamic>?,
      time: SessionMessageModelSwitchedTime.fromJson(json["time"] as Map<String, dynamic>),
      model: SessionMessageModelSwitchedModel.fromJson(json["model"] as Map<String, dynamic>),
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
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionMessageModelSwitched &&
          other.id == id &&
          const DeepCollectionEquality().equals(other.metadata, metadata) &&
          other.time == time &&
          other.model == model);

  @override
  int get hashCode => Object.hash(id, const DeepCollectionEquality().hash(metadata), time, model);

  final String id;
  final Map<String, dynamic>? metadata;
  final SessionMessageModelSwitchedTime time;
  final SessionMessageModelSwitchedModel model;
}

@immutable
class SessionMessageModelSwitchedTime {
  const SessionMessageModelSwitchedTime({
    required this.created,
  });

  factory SessionMessageModelSwitchedTime.fromJson(Map<String, dynamic> json) {
    return SessionMessageModelSwitchedTime(
      created: (json["created"] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "created": created,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionMessageModelSwitchedTime &&
          other.created == created);

  @override
  int get hashCode => created.hashCode;

  final double created;
}

@immutable
class SessionMessageModelSwitchedModel {
  const SessionMessageModelSwitchedModel({
    required this.id,
    required this.providerID,
    this.variant,
  });

  factory SessionMessageModelSwitchedModel.fromJson(Map<String, dynamic> json) {
    return SessionMessageModelSwitchedModel(
      id: json["id"] as String,
      providerID: json["providerID"] as String,
      variant: json["variant"] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "providerID": providerID,
      "variant": ?variant,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionMessageModelSwitchedModel &&
          other.id == id &&
          other.providerID == providerID &&
          other.variant == variant);

  @override
  int get hashCode => Object.hash(id, providerID, variant);

  final String id;
  final String providerID;
  final String? variant;
}
