// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'session_message.dart';

@immutable
class SessionMessageSynthetic implements SessionMessage {
  const SessionMessageSynthetic({
    required this.id,
    this.metadata,
    required this.time,
    required this.sessionID,
    required this.text,
  });

  factory SessionMessageSynthetic.fromJson(Map<String, dynamic> json) {
    return SessionMessageSynthetic(
      id: json["id"] as String,
      metadata: json["metadata"] as Map<String, dynamic>?,
      time: SessionMessageSyntheticTime.fromJson(json["time"] as Map<String, dynamic>),
      sessionID: json["sessionID"] as String,
      text: json["text"] as String,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "metadata": ?metadata,
      "time": time.toJson(),
      "sessionID": sessionID,
      "text": text,
      "type": "synthetic",
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionMessageSynthetic &&
          other.id == id &&
          const DeepCollectionEquality().equals(other.metadata, metadata) &&
          other.time == time &&
          other.sessionID == sessionID &&
          other.text == text);

  @override
  int get hashCode => Object.hash(id, const DeepCollectionEquality().hash(metadata), time, sessionID, text);

  final String id;
  final Map<String, dynamic>? metadata;
  final SessionMessageSyntheticTime time;
  final String sessionID;
  final String text;
}

@immutable
class SessionMessageSyntheticTime {
  const SessionMessageSyntheticTime({
    required this.created,
  });

  factory SessionMessageSyntheticTime.fromJson(Map<String, dynamic> json) {
    return SessionMessageSyntheticTime(
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
      (other is SessionMessageSyntheticTime &&
          other.created == created);

  @override
  int get hashCode => created.hashCode;

  final double created;
}
